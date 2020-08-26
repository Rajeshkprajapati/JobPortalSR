using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.SuccessStory;
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
    public class SuccessStoryVideoController : Controller
    {
        private readonly ISuccessStoryVideoHandler _successStoryVideoHandler;

        public SuccessStoryVideoController(ISuccessStoryVideoHandler successStoryVideoHandler)
        {
            _successStoryVideoHandler = successStoryVideoHandler;
        }
        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult GetSuccessStoryVideo()
        {
            List<SuccessStoryVideoViewModel> list = new List<SuccessStoryVideoViewModel>();
            try
            {
                list = _successStoryVideoHandler.GetSuccessStoryVid();
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(SuccessStoryVideoController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return View(list);
        }

        [HttpPost]
        [Route("[action]")]
        public IActionResult InsertUpdateSuccessStoryVideo([FromBody]SuccessStoryVideoViewModel model)
        {

            int id = 0;
            var result = false;
            try
            {
                {
                    var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
                    result = _successStoryVideoHandler.InsertUpdateSuccessStoryVid(model,user.FirstName);

                };
            }

            catch (DataNotUpdatedException ex)
            {
                return Json(ex);
            }
            if (result && id != 0)
            {
                //return View();
                return Json("Record Updated");
            }
            else if (result && id == 0)
            {
                return Json("Record Added");
            }

            return Json("Unable to do this action");
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult DeleteSuccessStoryVideo(string id)
        {
            var result = false;
            try
            {
                var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
                result = _successStoryVideoHandler.DeleteSuccessStoryVid(id, Convert.ToString(user.Email));
            }
            catch (DataNotUpdatedException ex)
            {
                return Json(ex);
            }

            if (result == true)
            {
                //return View();
                return Json("Record Deleted");
            }
            return Json("Record Can't be Deleted");

        }
    }
}