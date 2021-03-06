﻿using System;
using System.Collections.Generic;
using JobPortal.Business.Interfaces.Employer.JobPost;
using JobPortal.Model.DataViewModel.Employer.JobPost;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace JobPortal.Web.Areas.Employer.Controllers
{
    [Area("Employer")]
    [Route("[controller]")]
    //[HandleExceptionsAttribute]
    [UserAuthentication(Constants.CorporateRole + "," + Constants.StaffingPartnerRole)]
    public class JobManagementController : Controller
    {
        private readonly IJobPostHandler jobpastHandler;
        public JobManagementController(IJobPostHandler _jobpastHandler)
        {
            jobpastHandler = _jobpastHandler;
        }
        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult JobPosting()
        {
            try
            {
                string msg = Convert.ToString(TempData["msg"]);
                if (msg != "" || msg != null)
                {
                    ViewData["SuccessMessage"] = msg;
                }
                ViewBag.JobTitle = jobpastHandler.GetJobTitleDetails();
                ViewBag.JobIndustryArea = jobpastHandler.GetJobIndustryAreaDetails();
                //ViewBag.Gender = jobpastHandler.GetGenderListDetail();
                ViewBag.EmploymentStatus = jobpastHandler.GetJobJobEmploymentStatusDetails();
                ViewBag.EmploymentType = jobpastHandler.GetJobJobEmploTypeDetails();
                ViewBag.Country = jobpastHandler.GetCountryDetails();
                ViewBag.JobTypes = jobpastHandler.GetJobTypes();
                return View();
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(JobManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return View();
        }


        [HttpPost]
        [Route("[action]")]
        public IActionResult AddJobPost([FromBody]JobPostViewModel model)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            var msg = true;
            try
            {
                jobpastHandler.AddJobPost(model, user.UserId);
                //TempData["msg"] = "Job Posted successfully";                
            }
            catch (UserNotCreatedException ex)
            {
                msg = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));

            }
            //return RedirectToAction("JobPosting", "JobManagement");
            return Json(msg);
        }
        [HttpPost]
        [Route("[action]")]
        public IActionResult SaveJobPost([FromBody]JobPostViewModel model)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            var msg = true;
            try
            {
                jobpastHandler.AddJobPost(model, user.UserId,true);
                //TempData["msg"] = "Job Posted successfully";                
            }
            catch (UserNotCreatedException ex)
            {
                msg = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));

            }
            //return RedirectToAction("JobPosting", "JobManagement");
            return Json(msg);
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult StateDetails(string CountryCode)
        {
            var statelist = new List<StateViewModel>();
            try
            {
                statelist = jobpastHandler.GetStateList(CountryCode);

            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(JobManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json(statelist);
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult CityDetails(string stateCode)
        {
            var cityList = new List<CityViewModel>();
            try
            {
                cityList = jobpastHandler.GetCityList(stateCode);

            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(JobManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json(cityList);
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult JobTitles(int JobIndustryAreaId)
        {
            var jobTitle = new List<JobTitleViewModel>();
            try
            {
                jobTitle = jobpastHandler.GetJobTitleById(JobIndustryAreaId);

            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(JobManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json(jobTitle);
        }
    }
}