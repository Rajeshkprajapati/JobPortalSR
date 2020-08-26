using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.Notifications;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Mvc;

namespace JobPortal.Web.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication(Constants.AdminRole + "," + Constants.DemandAggregationRole)]
    public class NotificationsController : Controller
    {
        private readonly INotificationHandler notificationHandler;

        public NotificationsController(INotificationHandler _notificationHandler)
        {
            notificationHandler = _notificationHandler;
        }

        [Route("[action]")]
        public JsonResult GetNotificationsCounter()
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            NotificationsViewModel counts = null;
            try
            {
                counts=notificationHandler.GetNotificationsCounter();
                return new JsonResult(new { counts });
            }

            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(NotificationsController), ex);
                counts = new NotificationsViewModel();
            }
            return new JsonResult(new { counts });
        }
    }
}