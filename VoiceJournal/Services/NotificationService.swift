 import Foundation
 import UserNotifications
 
 /// Manages local push notifications to remind users to journal.
 struct NotificationService {
     
     private let center = UNUserNotificationCenter.current()
     
     func requestAuthorization() {
         center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
             if !granted { print("Notification permission denied") }
         }
     }
     
     /// Returns true if notifications are authorized
     private func checkAuthorization(completion: @escaping (Bool) -> Void) {
         center.getNotificationSettings { settings in
             completion(settings.authorizationStatus == .authorized)
         }
     }
     
     func scheduleDailyReminder(at hour: Int = 20, minute: Int = 0) {
         checkAuthorization { authorized in
             guard authorized else { return }
             self.cancelAll()
             
             let content = UNMutableNotificationContent()
             content.title = "Time to reflect"
             content.body = "Take a moment to record your thoughts for today."
             content.sound = .default
             
             var dateComponents = DateComponents()
             dateComponents.hour = hour
             dateComponents.minute = minute
             
             let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
             let request = UNNotificationRequest(
                 identifier: "daily_journal_reminder",
                 content: content,
                 trigger: trigger
             )
             self.center.add(request)
         }
     }
     
     func scheduleEveningPrompt() {
         checkAuthorization { authorized in
             guard authorized else { return }
             
             let content = UNMutableNotificationContent()
             content.title = "How was your day?"
             content.body = "A quick voice note takes just 30 seconds."
             content.sound = .default
             
             var components = DateComponents()
             components.hour = 21
             components.minute = 0
             
             let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
             let request = UNNotificationRequest(
                 identifier: "evening_prompt",
                 content: content,
                 trigger: trigger
             )
             self.center.add(request)
         }
     }
     
     func cancelAll() {
         center.removeAllPendingNotificationRequests()
     }
 }
