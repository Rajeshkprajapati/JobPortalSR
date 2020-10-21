using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Text.RegularExpressions;
using JobPortal.Business.Interfaces.Employer.JobPost;
using JobPortal.Business.Interfaces.Home;
using JobPortal.Business.Interfaces.Jobseeker;
using JobPortal.Model.DataViewModel.Employer.JobPost;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;

namespace JobPortal.Web.Areas.Jobseeker.Controllers
{
    [Area("Jobseeker")]
    [Route("[controller]")]

    [HandleExceptionsAttribute]
    public class JobController : Controller
    {
        private readonly IUserProfileHandler userProfileHandler;
        private readonly IJobPostHandler jobpastHandler;
        private readonly IHomeHandler homeHandler;
        private readonly ISearchJobHandler searchJobHandler;
        private readonly IConfiguration config;
        private readonly string URLprotocol;
        private readonly IHttpContextAccessor _httpContextAccessor;
        public JobController(IJobPostHandler _jobpastHandler, IHomeHandler _homeHandler, IConfiguration _config,
            IHttpContextAccessor httpContextAccessor,IUserProfileHandler _userProfileHandler, ISearchJobHandler _searchJobHandler)
        {
            jobpastHandler = _jobpastHandler;
            homeHandler = _homeHandler;
            searchJobHandler = _searchJobHandler;
            userProfileHandler = _userProfileHandler;
            config = _config;
            _httpContextAccessor = httpContextAccessor;
            URLprotocol = config["URLprotocol"];
        }

        public IActionResult Index()
        {
            return View();
        }

        //[HttpGet]
        //[Route("[action]")]
        //public IActionResult SearchJobList([FromQuery]SearchJobViewModel searches)
        //{

        //    return View();
        //}

        [HttpPost]
        [HttpGet]
        [Route("[action]")]
        public IActionResult SearchJobList(SearchJobViewModel searches)
        {
            List<SearchJobListViewModel> lstjobList = new List<SearchJobListViewModel>();
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            Logger.Logger.WriteLog(Logger.Logtype.Information, JsonConvert.SerializeObject(searches), user.UserId, typeof(JobController), new Exception("Info Logged"));
            try
            {
                if (null == user)
                {
                    user = new UserViewModel();
                }
                var props = searches.GetType().GetProperties();
                foreach (PropertyInfo prop in props)
                {
                    if (prop.PropertyType.IsArray)
                    {
                        var values = prop.GetValue(searches) as string[];
                        if (null != values)
                        {
                            List<string> finalValues = new List<string>();
                            foreach (var value in values)
                            {
                                if (null != value)
                                {
                                    finalValues.AddRange(value.Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries));
                                }
                            }
                            prop.SetValue(searches, finalValues.ToArray());
                        }
                    }
                }

                ViewBag.JobIndustryArea = jobpastHandler.GetJobIndustryAreaWithJobPost();
                ViewBag.City = homeHandler.GetCityHasJobPostId();
                ViewBag.Company = homeHandler.GetCompanyHasJobPostId();
                ViewBag.Searches = searches;
                var userip = _httpContextAccessor.HttpContext.Connection.RemoteIpAddress.ToString();                                
                searchJobHandler.LogSearchJob(searches,userip, user.UserId);
                Logger.Logger.WriteLog(Logger.Logtype.Information, JsonConvert.SerializeObject(searches), user.UserId, typeof(JobController), new Exception("Before searchjob Info Logged"));
                lstjobList = searchJobHandler.SearchJobList(searches ,user.UserId);
                Logger.Logger.WriteLog(Logger.Logtype.Information, JsonConvert.SerializeObject(searches), user.UserId, typeof(JobController), new Exception("After searchjob Info Logged"));
            }

            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            catch (Exception ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
            }
            return View(lstjobList);
        }


        [HttpGet]
        [Route("[action]")]
        //[UserAuthentication(Constants.JobSeekers)]
        public IActionResult ApplyJob(int jobPostId, string currentUrl)
        {
            string applyJobURL = currentUrl;
            HttpContext.Session.Set<string>(Constants.SessionRedirectUrl, applyJobURL);

            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            string result = "";
            try
            {
                if (user.UserId == 0)
                {
                    result = "Please login to apply this job";
                }

                else if (user.RoleName == "Student")
                {
                    if (userProfileHandler.ApplyJobDetails(user, jobPostId))
                    {
                        result = "Job applied";
                    }
                }
                else
                {
                    result = "Oops! Applicable For Job Seeker Only.";
                }
            }

            catch (FaildToApplyJob ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
                result = ex.Message;
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            catch (DataNotUpdatedException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
                result = ex.Message;
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }

            catch (AllReadyExistJob ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
                result = ex.Message;
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            catch (System.Net.Mail.SmtpFailedRecipientException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
                result = "Job applied";
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json(result);
        }


        [HttpGet]
        [Route("[action]")]
        //[UserAuthentication(Constants.AllRoles)]
        public IActionResult JobDetails(int jobid)
        {
            JobPostViewModel jobdetail = new JobPostViewModel();
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            try
            {
                var basePath = string.Format("{0}://{1}{2}", Request.Scheme, URLprotocol, Request.Host);
                //var basePath = string.Format("{0}", "http://18.221.113.108:83");
                var pageLink = "/Job/JobDetails/?jobid=";
                var fbUrl = "https://www.facebook.com/sharer/sharer.php?u=";
                var twitterUrl = "https://twitter.com/home?status=";
                var whatsAppUrl = "https://wa.me/?text=";
                var encodedlink = System.Web.HttpUtility.UrlEncode(basePath + pageLink);                
                ViewBag.FBUrl = string.Format("{0}{1}", fbUrl, basePath + pageLink);
                ViewBag.TwitterUrl = string.Format("{0}{1}", twitterUrl, basePath + pageLink);
                ViewBag.WhatsAppUrl = string.Format("{0}{1}", whatsAppUrl, encodedlink);
                jobdetail = jobpastHandler.GetJobDetails(jobid);
                ViewBag.jDetails = Regex.Replace(jobdetail.JobDetails, "<.*?>", String.Empty);
                if (user != null)
                {
                    List<int> appliedjobs = homeHandler.GetAplliedJobs(user.UserId);
                    //if(jobid == appliedjobs.)
                    for (int i = 0; i < appliedjobs.Count; i++)
                    {
                        //getting the all the jobs applied by user only if the user logged in
                        if (appliedjobs[i] == jobid)
                        {
                            jobdetail.IsApplied = true;
                            break;
                        }
                    }
                }

            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
                //result = ex.Message;
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return View(jobdetail);
        }

        [HttpGet]
        [Route("[action]")]
        [UserAuthentication(Constants.JobSeekers)]
        public IActionResult RecommendedJobs()
        {
            List<SearchJobListViewModel> list = new List<SearchJobListViewModel>();
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            try
            {
                //list = jobpastHandler.RecommendedJobs(user.SSCJobRoleId);
                if (user != null)
                {
                    List<int> appliedjobs = homeHandler.GetAplliedJobs(user.UserId);
                    for (int i = 0; i < appliedjobs.Count; i++)
                    {
                        list[i].IsApplied = appliedjobs.Any(aj => aj == list[i].JobPostId);
                    }
                }
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(JobController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return View(list);
        }
    }
}