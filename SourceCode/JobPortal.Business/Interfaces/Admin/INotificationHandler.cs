using JobPortal.Model.DataViewModel.Admin.Notifications;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.Admin
{
    public interface INotificationHandler
    {
        NotificationsViewModel GetNotificationsCounter();
    }
}
