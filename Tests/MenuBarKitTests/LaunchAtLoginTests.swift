import Testing
@testable import MenuBarKit

private struct RegistrationFailed: Error {}

@Suite("LaunchAtLogin")
@MainActor
struct LaunchAtLoginTests {
    @Test func readsTheInitialStatus() {
        #expect(LaunchAtLogin(service: InMemoryLoginItemService(status: .enabled)).isEnabled)
        #expect(!LaunchAtLogin(service: InMemoryLoginItemService(status: .notRegistered)).isEnabled)
        #expect(!LaunchAtLogin(service: InMemoryLoginItemService(status: .notFound)).isEnabled)
    }

    @Test func enablingRegistersAndDisablingUnregisters() {
        let service = InMemoryLoginItemService()
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.isEnabled = true
        #expect(service.registerCount == 1)
        #expect(launchAtLogin.status == .enabled)
        #expect(launchAtLogin.isEnabled)

        launchAtLogin.isEnabled = false
        #expect(service.unregisterCount == 1)
        #expect(launchAtLogin.status == .notRegistered)
    }

    @Test func settingTheSameValueDoesNothing() {
        let service = InMemoryLoginItemService(status: .enabled)
        let launchAtLogin = LaunchAtLogin(service: service)
        launchAtLogin.setEnabled(true)
        #expect(service.registerCount == 0)
    }

    @Test func approvalCountsAsEnabled() {
        let service = InMemoryLoginItemService(requiresApproval: true)
        let launchAtLogin = LaunchAtLogin(service: service)
        launchAtLogin.isEnabled = true
        #expect(launchAtLogin.status == .requiresApproval)
        #expect(launchAtLogin.requiresApproval)
        #expect(launchAtLogin.isEnabled)
    }

    @Test func failureKeepsTheStatusAndReportsAnError() {
        let service = InMemoryLoginItemService()
        service.failure = RegistrationFailed()
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.isEnabled = true
        #expect(launchAtLogin.status == .notRegistered)
        #expect(!launchAtLogin.isEnabled)
        #expect(launchAtLogin.errorMessage != nil)

        service.failure = nil
        launchAtLogin.isEnabled = true
        #expect(launchAtLogin.isEnabled)
        #expect(launchAtLogin.errorMessage == nil)
    }

    @Test func refreshPicksUpChangesMadeInSystemSettings() {
        let service = InMemoryLoginItemService()
        let launchAtLogin = LaunchAtLogin(service: service)
        service.status = .enabled
        #expect(!launchAtLogin.isEnabled)
        launchAtLogin.refresh()
        #expect(launchAtLogin.isEnabled)
    }
}
