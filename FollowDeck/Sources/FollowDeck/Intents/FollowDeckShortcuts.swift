//
//  FollowDeckShortcuts.swift
//  FollowDeck
//
//  Expose the app's intents as Siri and Shortcuts home-screen suggestions. Entity
//  parameters resolve through the AppEntity queries in Entities.swift. AppShortcuts
//  are available on iOS 16.0+; the deployment target is iOS 17.0, so no version gate
//  is required here.
//

import AppIntents

struct FollowDeckShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListUpNextIntent(),
            phrases: [
                "Show what's next in \(.applicationName)",
                "What follow-ups are due in \(.applicationName)"
            ],
            shortTitle: "Up next",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: AddFollowUpIntent(),
            phrases: ["Add a follow-up in \(.applicationName)"],
            shortTitle: "Add follow-up",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: LogInteractionIntent(),
            phrases: ["Log an interaction in \(.applicationName)"],
            shortTitle: "Log interaction",
            systemImageName: "pencil"
        )
        AppShortcut(
            intent: CompleteFollowUpIntent(),
            phrases: ["Complete a follow-up in \(.applicationName)"],
            shortTitle: "Complete follow-up",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: ClientStatusIntent(),
            phrases: ["Check a client in \(.applicationName)"],
            shortTitle: "Client status",
            systemImageName: "person"
        )
        AppShortcut(
            intent: SuggestNextStepIntent(),
            phrases: ["Suggest a next step in \(.applicationName)"],
            shortTitle: "Next step",
            systemImageName: "sparkles"
        )
    }
}
