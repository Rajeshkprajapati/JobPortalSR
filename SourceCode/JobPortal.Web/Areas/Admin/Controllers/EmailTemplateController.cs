using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.Notifications;
//using JobPortal.Model.DataViewModel.Admin.UsersReviews;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace JobPortal.Web.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication("Admin")]
    public class EmailTemplateController : Controller
    {
        private readonly IEmailTemplateHandler _emailTemplateHandler;
        public EmailTemplateController(IEmailTemplateHandler emailTemplateHandler)
        {
            _emailTemplateHandler = emailTemplateHandler;
        }

        [HttpGet]
        [Route("[action]")]
        public PartialViewResult EmailTemplates()
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            List<EmailTemplateViewModel> list = new List<EmailTemplateViewModel>();
            try
            {
                list = _emailTemplateHandler.GetEmailTemplates(user.RoleId);
            }
            catch (DataNotFound ex)
            {
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return PartialView("EmailTemplatesPartial", list);
        }
        [HttpPost]
        [Route("[action]")]
        public IActionResult UpdateEmailTemplate([FromBody]EmailTemplateViewModel model)
        {
            try
            {
                var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);

                var data = _emailTemplateHandler.UpdateEmailTemplate(model, Convert.ToString(user.UserId));

                return Json(data);
            }
            catch (Exception ex)
            {
                return Json(ex.Message);
            }
        }

        [HttpPost]
        [Route("[action]")]
        public IActionResult InsertEmailTemplate([FromBody]EmailTemplateViewModel model)
        {
            try
            {
                var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);

                var data = _emailTemplateHandler.InsertEmailTemplate(model, Convert.ToString(user.UserId));

                return Json(data);
            }
            catch (Exception ex)
            {
                return Json(ex.Message);
            }
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult DeleteEmailTemplate(int Id)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);

            var result = _emailTemplateHandler.DeleteUsersReviews(Id, user.UserId);
            if (result)
            {
                //return View();
                return Json(result);
            }
            return Json(result);
            //return View();
        }
    }
}