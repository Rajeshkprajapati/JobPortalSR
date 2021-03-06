﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Data.DataModel.Admin.JobIndustryArea;
using JobPortal.Utility.Exceptions;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.JobIndustryArea;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Helpers;

namespace JobPortal.Web.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication("Admin")]
    public class JobIndustryAreaController : Controller
    {
        private readonly IJobIndustryAreaHandler _jobIndustryAreaHandler;
        public JobIndustryAreaController(IJobIndustryAreaHandler jobIndustryAreaHandler)
        {
            _jobIndustryAreaHandler = jobIndustryAreaHandler;
        }
        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult GetJobIndustryArea()
        {
            List<JobIndustryAreaViewModel> list = new List<JobIndustryAreaViewModel>();
            try
            {
                    list = _jobIndustryAreaHandler.GetJobIndustryAreaList();
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(JobIndustryAreaController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return View(list);
        }
        [HttpPost]
        [Route("[action]")]
        public IActionResult UpdateJobIndustryArea([FromBody]JobIndustryAreaViewModel jobIndustryArea)
        {

            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            
            var result = _jobIndustryAreaHandler.UpdateJobIndustryArea(jobIndustryArea);
            if (result && jobIndustryArea.JobIndustryAreaId != 0)
            {
                return Json("Record Updated");
            }
            else if (result && jobIndustryArea.JobIndustryAreaId == 0)
            {
                return Json("Record Added");
            }
           
            return Json("Unable to do this action");
        }
        [HttpGet]
        [Route("[action]")]
        public IActionResult DeleteJobIndustryArea(string jobIndustryAreaId)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            var result = _jobIndustryAreaHandler.DeleteJobIndustryArea(jobIndustryAreaId, Convert.ToString(user.UserId));
            if (result)
            {
                //return View();
                return Json("Record Deleted");
            }
            return Json("Record Can't be Deleted");
            //return View();
        }

       
    }
}