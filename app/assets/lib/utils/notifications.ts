export function hasPermissionToNotify(): boolean {
  return Notification.permission === "granted";
}

export function permissionToNotifyExplicitlyDenied(): boolean {
  return Notification.permission === "denied";
}

export function requestNotificationPermission() {

}

export function supportsNotifications(): boolean {
  return "Notification" in window;
}

export async function notify(title: string, options?: NotificationOptions): Promise<boolean> {
  if (!supportsNotifications()) {
    return false;
  } else if (hasPermissionToNotify()) {
    sendNotification(title, options);
    return true;
  } else {
    let permission = await Notification.requestPermission();
    if (permission === "granted") {
      sendNotification(title, options);
    } else {
      return false;
    }
  }
  return false;
}

function sendNotification(title: string, options: NotificationOptions = {}): Notification {
  let notification = new Notification(title, options);
  notification.onclick = function () {
    parent.focus();
    window.focus(); //just in case, older browsers
    this.close();
  };
  return notification;
}