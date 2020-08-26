using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Admin
{
    public interface INotificationRepository
    {
        DataSet GetNotificationsCounter();
    }
}
