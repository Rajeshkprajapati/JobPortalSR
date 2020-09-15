using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.Advertisements;
using JobPortal.Model.DataViewModel.Employer.JobPost;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;

namespace JobPortal.Web.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication(Constants.AdminRole + "," + Constants.DemandAggregationRole)]
    public class DigitalDisplayController : Controller
    {
        private readonly IAdvertisementsHandler _advertisementsHandler;
        private readonly IHostingEnvironment _hostingEnviroment;

        public DigitalDisplayController(IAdvertisementsHandler advertisementsHandler, IHostingEnvironment hostingEnvironment)
        {
            _advertisementsHandler = advertisementsHandler;
            _hostingEnviroment = hostingEnvironment;
        }
        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        [Route("[action]")]
        public PartialViewResult GetAllData(int section = 0)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            IEnumerable<AdvertisementsViewModel> model;
            try
            {
                model = _advertisementsHandler.GetAllData(section);
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                model = null;
            }
            catch (Exception ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                model = null;
            }
            return PartialView("ManageAdvertisementPartial", model);
        }
        

        [HttpPost]
        [Route("[action]")]
        public JsonResult AddDigitalDisplayData([FromForm]AdvertisementsViewModel model)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            var resp = false;
            string fName = "";
            if (model.ImageFile != null)
            {
                //var file = Request.Form.Files[0];
                //var file = Request.Form.Files[0];
                var file = model.ImageFile;
                string filename = model.ImageFile.FileName;

                fName = $@"\Ads\{user.UserId + "_" + filename}";
                filename = _hostingEnviroment.WebRootPath + fName;
                using (FileStream fs = System.IO.File.Create(filename))
                {
                    file.CopyTo(fs);
                }
            }
            try
            {
                model.Id = user.UserId;
                model.ImagePath = fName;
                resp = _advertisementsHandler.AddAds(model);
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                resp = false;
            }
            catch (Exception ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                resp = false;
            }
            return Json(resp);
        }

        [HttpPost]
        [Route("[action]")]
        public JsonResult UpdateDigitalDisplayData([FromForm]AdvertisementsViewModel model)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            var resp = false;
            string fName = "";
            if (model.ImageFile != null)
            {
                //var file = Request.Form.Files[0];
                //var file = Request.Form.Files[0];
                var file = model.ImageFile;
                string filename = model.ImageFile.FileName;

                fName = $@"\Ads\{user.UserId + "_" + filename}";
                filename = _hostingEnviroment.WebRootPath + fName;
                using (FileStream fs = System.IO.File.Create(filename))
                {
                    file.CopyTo(fs);
                }
            }
            try
            {
                model.Id = user.UserId;
                model.ImagePath = fName;
                resp = _advertisementsHandler.UpdateAds(model, user.UserId);
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                resp = false;
            }
            catch (Exception ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                resp = false;
            }
            return Json(resp);
        }
        [HttpPost]
        [Route("[action]")]
        public JsonResult DeleteDigitalDisplayData([FromBody]int adid)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            var resp = false;

            try
            {
                resp = _advertisementsHandler.DeleteAds(adid);
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                resp = false;
            }
            catch (Exception ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(DigitalDisplayController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                resp = false;
            }
            return Json(resp);
        }

    }
}