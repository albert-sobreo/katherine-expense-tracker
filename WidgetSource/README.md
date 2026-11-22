# Home Screen widget

The widget code is ready in `KatherineWidget.swift`, but Xcode has to create the widget target (that part can't be done by editing files safely).

1. In Xcode: **File → New → Target… → Widget Extension**. Name it `KatherineWidget`. Uncheck "Include Live Activity" and "Include Configuration App Intent". When asked to activate the scheme, choose Activate (or Cancel; either is fine).
2. Xcode creates a `KatherineWidget` folder with sample files. Delete the generated Swift files in it (move to Trash), then drag `WidgetSource/KatherineWidget.swift` into that folder, with only the **KatherineWidget** target checked.
3. Select the **KatherineWidget** target → Signing & Capabilities → **+ Capability → App Groups** → add `group.katherine.expensetracker`.
4. Select the **KatherineExpenseTracker** (app) target → Signing & Capabilities → check that **App Groups** shows `group.katherine.expensetracker` too (it's already in the app's entitlements file). If the box is unchecked, check it.
5. Set the widget target's iOS deployment target to 18.0, like the app, build and run the app once, then add the widget from the Home Screen.

The app writes this month's numbers to the App Group whenever they change; the widget just reads them.
