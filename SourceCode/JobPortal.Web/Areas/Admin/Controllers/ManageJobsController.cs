using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Handlers.Admin;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Business.Interfaces.Home;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Mvc;

namespace JobPortal.Web.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication(Constants.AdminRole)]
    public class ManageJobsController : Controller
    {
        private readonly IHomeHandler _homeHandler;
        private readonly IManageJobsHandler _managejobshandler;
        public ManageJobsController(IHomeHandler homeHandler, IManageJobsHandler managejobshandler)
        {
            _homeHandler = homeHandler;
            _managejobshandler = managejobshandler;
        }
        public ViewResult Jobs()
        {
            return View();
        }

        [HttpGet]
        [Route("[action]")]
        public PartialViewResult FeaturedJobs()
        {
            List<SearchJobListViewModel> list = new List<SearchJobListViewModel>();
            try
            {
                list = _homeHandler.ViewAllFeaturedJobs();
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageJobsController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return PartialView("FeaturedJobs", list);
        }

        [HttpGet]
        [Route("[action]")]
        public JsonResult UpdateFeaturedJobDisplayOrder(int JobPostId,int FeaturedJobDisplayOrder)
        {
            string result = string.Empty;
            try
            {
                if (JobPostId != 0 && _managejobshandler.UpdateFeaturedJobDisplayOrder(JobPostId, FeaturedJobDisplayOrder))
                {
                    result = "Updated display Order";
                }
            }
            catch (Exception ex)
            {
                result = ex.Message;
            }
            return Json(new { msg = result});
        }
        [HttpGet]
        [Route("[action]")]
        public JsonResult DeleteFeaturedJob(int jobpostid)
        {
            string result = string.Empty;
            try
            {
                if (_managejobshandler.DeleteFeaturedJob(jobpostid))
                {
                    result = "Removed Featured Job";
                }
            }
            catch (Exception ex)
            {
                result = ex.Message;
            }
            return Json(new { msg = result });
        }
    }
}