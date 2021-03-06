﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using JobPortal.Business.Interfaces.Employer.SearchResume;
using JobPortal.Model.DataViewModel.Employer.SearchResume;

using JobPortal.Business.Interfaces.Employer.JobPost;
using JobPortal.Business.Interfaces.Home;
using JobPortal.Business.Interfaces.Jobseeker;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Web.Filters;
using JobPortal.Business.Interfaces.Employer.Profile;
using JobPortal.Utility.Exceptions;
using JobPortal.Data.DataModel.Shared;
using System.IO;
using Microsoft.AspNetCore.Hosting;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;

namespace JobPortal.Web.Areas.Employer.Controllers
{
    [Area("Employer")]
    [Route("[controller]")]
    [UserAuthentication(Constants.CorporateRole + "," + Constants.StaffingPartnerRole)]
    public class EmployerManagementController : Controller
    {
        private readonly IJobPostHandler jobpastHandler;
        private readonly IHomeHandler homeHandler;
        //private readonly ISearchJobHandler searchJobHandler;
        private readonly ISearchResumeHandler searchresumehandler;
        private readonly IEmpProfileHandler empProfileHandler;
        private IHostingEnvironment hostingEnviroment;
        public EmployerManagementController(IJobPostHandler _jobpastHandler, IHomeHandler _homeHandler, ISearchResumeHandler _searchResumeHandler, IEmpProfileHandler _empProfileHandler, IHostingEnvironment _hostingEnvironment)
        {
            searchresumehandler = _searchResumeHandler;
            jobpastHandler = _jobpastHandler;
            homeHandler = _homeHandler;
            empProfileHandler = _empProfileHandler;
            hostingEnviroment = _hostingEnvironment;
        }

        public IActionResult Index()
        {
            return RedirectToAction("Index", "Home");
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult DashBoard()
        {
                return View();
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult EditProfile()
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            var result = empProfileHandler.GetEmpProfileDetail(user.UserId);
            var genders = empProfileHandler.GetAllGenders();
            var maritalStatuses = empProfileHandler.GetMaritalStatusMaster();
            return Json(new { genders = genders, maritalStatuses= maritalStatuses, userDetail =result });
        }

        [HttpPost]
        [Route("[action]")]
        public IActionResult UpdateProfile([FromForm]UserViewModel model)
        {
            string fName = "";
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            //if (Request.Form.Files.Count > 0)
            if (model.ImageFile != null)
            {
                //var file = Request.Form.Files[0];
                //var file = Request.Form.Files[0];
                var file = model.ImageFile;
                string filename = model.ImageFile.FileName;

                fName = $@"\ProfilePic\{user.UserId + "_" + filename}";
                filename = hostingEnviroment.WebRootPath + fName;
                using (FileStream fs = System.IO.File.Create(filename))
                {
                    file.CopyTo(fs);
                }
            }
            var result = false;
            try
            {
                model.ProfilePic = fName;
                model.UserId = user.UserId;
                result = empProfileHandler.InsertUpdateEmpDetail(model);
                if (result)
                {
                    user.CompanyName = model.CompanyName;
                    user.ProfilePic = !string.IsNullOrEmpty(model.ProfilePic) ? model.ProfilePic : user.ProfilePic;
                }
                //HttpContext.Session.Set<UserViewModel>(Constants.SessionKeyUserInfo, model);
            }
            catch (InvalidUserCredentialsException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(EmployerManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            catch (UserNotCreatedException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(EmployerManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json(result);

        }


        [HttpGet]
        [Route("[action]")]
        public IActionResult GetCityListChar(string cityFirstChar)
        {
            var result = new List<CityViewModel>();
            try
            {
                result = homeHandler.GetCityListByChar(cityFirstChar);
            }

            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(EmployerManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            catch (InvalidUserCredentialsException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(EmployerManagementController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json(result);

        }

        //[HttpPost]
        //[Route("[action]")]
        //public IActionResult SearchResume(string skill, string categories, string experience, string location)
        //{
        //    ViewBag.JobTitle = jobpastHandler.GetJobTitleDetails();
        //    ViewBag.JobIndustryArea = jobpastHandler.GetJobIndustryAreaDetails();
        //    ViewBag.City = homeHandler.GetCityList();
        //    ViewBag.EmploymentStatus = jobpastHandler.GetJobJobEmploymentStatusDetails();
        //    List<SearchResumeListViewModel> listresume = new List<SearchResumeListViewModel>();
        //    listresume = searchresumehandler.GetSearchResumeList(skill, categories, experience, location);
        //    return View(listresume);
        //}
    }
}