using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Admin.Notifications
{
    public class NotificationsViewModel
    {
        public int NewAddedUsersCount { get; set; }
        public int TotalNotifications { get { return NewAddedUsersCount; } }
    }
}
