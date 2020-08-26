using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.TrainingPartner;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Model.DataViewModel.TrainingPartner;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Mvc;

namespace JobPortal.Web.Areas.TrainingPartner.Controllers
{
    [Area("TrainingPartner")]
    [Route("[controller]")]
    [UserAuthentication(Constants.TrainingPartnerRole)]
    public class DashboardController : Controller
    {
        private readonly IDashboardHandler dashboardHandler;

        public DashboardController(IDashboardHandler _dashboardHandler)
        {
            dashboardHandler = _dashboardHandler;
        }

        [Route("[action]")]
        public IActionResult TPDashboard()
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            IList<CandidatesViewModel> candidates = null;
            user = user ?? new UserViewModel();
            try
            {
                candidates = dashboardHandler.GetCandidates(user.UserId);
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(DashboardController), ex);
            }
            if (candidates == null)
            {
                return RedirectToAction("Index", "BulkJobSeeker", new { area = "TrainingPartner" });
            }
            else {
                return View(candidates);
            }
           
        }
        [HttpGet]
        [Route("[action]")]
        public PartialViewResult CandidateDetail(int userid)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            CandidatesViewModel candidatedetail = null;
            try
            {
                candidatedetail = dashboardHandler.GetCandidateDetails(userid);
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(DashboardController), ex);
            }
            return PartialView("CandidateDetailFormPartial", candidatedetail);
        }

        [HttpGet]
        [Route("[action]")]
        public JsonResult DeleteCandidate(int userid)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            bool isSuccess = true;
            try
            {
                isSuccess = dashboardHandler.DeleteCandidate(userid);
            }
            catch (DataNotFound ex)
            {
                isSuccess = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(DashboardController), ex);
            }
            return Json(new { isSuccess });
        }

        [HttpPost]
        [Route("[action]")]
        public JsonResult UpdateCandidate([FromBody]CandidatesViewModel candidate)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            bool isUpdated = true;
            try
            {
                isUpdated = dashboardHandler.UpdateCandidateDetails(candidate);
            }
            catch (DataNotFound ex)
            {
                isUpdated = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(DashboardController), ex);
            }
            return Json(new { isUpdated });
        }
    }
}