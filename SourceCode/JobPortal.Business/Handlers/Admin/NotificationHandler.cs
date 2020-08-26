using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.Notifications;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace JobPortal.Business.Handlers.Admin
{
    public class NotificationHandler: INotificationHandler
    {
        private readonly INotificationRepository notificationRepository;

        public NotificationHandler(IConfiguration configuration)
        {
            var factory = new ProcessorFactoryResolver<INotificationRepository>(configuration);
            notificationRepository = factory.CreateProcessor();
        }

        public NotificationsViewModel GetNotificationsCounter()
        {
            var notifications = notificationRepository.GetNotificationsCounter();
            NotificationsViewModel counts = new NotificationsViewModel();
            if (notifications!=null && notifications.Tables.Count > 0)
            {
                counts.NewAddedUsersCount = Convert.ToInt32(notifications.Tables[0].Rows[0]["TotalNewUsers"]);
            }
            return counts;
        }
    }
}
