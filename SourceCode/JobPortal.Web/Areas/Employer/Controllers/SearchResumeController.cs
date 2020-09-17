using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.Employer.JobPost;
using JobPortal.Business.Interfaces.Employer.SearchResume;
using JobPortal.Business.Interfaces.Home;
using JobPortal.Business.Interfaces.Jobseeker;
using JobPortal.Business.Interfaces.Shared;
using JobPortal.Model.DataViewModel.Employer.AdvanceSearch;
using JobPortal.Model.DataViewModel.Employer.SearchResume;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;


namespace JobPortal.Web.Areas.Employer.Controllers
{
    [Area("Employer")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication(Constants.CorporateRole + "," + Constants.StaffingPartnerRole)]
    public class SearchResumeController : Controller
    {

        private readonly IJobPostHandler jobpastHandler;
        private readonly IHomeHandler homeHandler;
        private readonly ISearchResumeHandler searchresumehandler;
        private readonly IEMailHandler emailHandler;
        private readonly IConfiguration config;
        private readonly IHttpContextAccessor _httpContextAccessor;
        public SearchResumeController(IEMailHandler _emailHandler, IConfiguration _config, IJobPostHandler _jobpastHandler,
            IHttpContextAccessor httpContextAccessor, IHomeHandler _homeHandler, ISearchResumeHandler _searchResumeHandler)
        {
            jobpastHandler = _jobpastHandler;
            homeHandler = _homeHandler;
            searchresumehandler = _searchResumeHandler;
            emailHandler = _emailHandler;
            _httpContextAccessor = httpContextAccessor;
            config = _config;
        }
        public IActionResult Index()
        {
            return View();
        }
        [HttpPost]
        [HttpGet]
        [Route("[action]")]
        public IActionResult SearchResumeList(SearchResumeViewModel searches)
        {
            List<SearchResumeListViewModel> lstResumeList = new List<SearchResumeListViewModel>();
            try
            {
                var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
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
                ViewBag.JobIndustryArea = jobpastHandler.GetJobIndustryAreaWithStudentData();
                ViewBag.City = homeHandler.GetCitiesWithJobSeekerInfo();
                ViewBag.Searches = searches;
                //GeoCoordinateWatcher watcher = new GeoCoordinateWatcher();
                var userip = _httpContextAccessor.HttpContext.Connection.RemoteIpAddress.ToString();
                searchresumehandler.LogSearchResumeList(searches, userip, user.UserId);
                lstResumeList = searchresumehandler.GetSearchResumeList(searches);
            }

            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(SearchResumeController), ex);
            }
            return View(lstResumeList);
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult ShowCandidateDetail(int userId)
        {
            SearchResumeListViewModel listresume = new SearchResumeListViewModel();
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            try
            {
                listresume = searchresumehandler.ShowCandidateDetails(user.UserId, userId);
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(SearchResumeController), ex);
                //ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return View(listresume);
        }


        [HttpGet]
        [Route("[action]")]
        public IActionResult SendMessage(string userEmail, string JobSeekerName)
        {
            bool isSend = true;
            string errorMessage;
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo) ?? new UserViewModel();
            JobSeekerName = string.IsNullOrWhiteSpace(JobSeekerName) ? "Candidate" : JobSeekerName;
            try
            {
                var eModel = new EmailViewModel
                {
                    Subject = "New Job from Placement Portal",
                    Body = "Dear " + JobSeekerName + ",<br/>Your resume has been shortlisted by " + user.CompanyName + ".<br/>The employer will connect with you for further processing.<br/><br/>Thank You<br/>Placement Portal Team",
                    To = new string[] { userEmail },
                    From = config["EmailCredential:Fromemail"],
                    IsHtml = true,
                    MailType = (int)MailType.NotAllowed
                };
                emailHandler.SendMail(eModel, -1);

                errorMessage = "Your mail has been successfully send to the Jobseeker";
                return Json(new { isSend, errorMessage });
            }
            catch
            {
                ViewData["Error"] = "your mail has not been send";
                isSend = false;
                errorMessage = "mail not send";

            }
            return Json(new { isSend, errorMessage });
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult AdvanceResumeSearch()
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            ViewBag.JobTitle = jobpastHandler.GetJobTitleDetails();
            ViewBag.JobIndustryArea = jobpastHandler.GetJobIndustryAreaDetails();
            ViewBag.EmploymentStatus = jobpastHandler.GetJobJobEmploymentStatusDetails();
            ViewBag.EmploymentType = jobpastHandler.GetJobJobEmploTypeDetails();
            ViewBag.JobTypes = jobpastHandler.GetJobTypes();
            ViewBag.CityData = searchresumehandler.GetCityList();
            ViewBag.GenderData = searchresumehandler.GetGenders();
            ViewBag.EmployersData = searchresumehandler.GetEmployers(true);
            ViewBag.AdvanceSearchStats = searchresumehandler.AdvanceSearchStates(user.UserId);
            return View();
        }
        [HttpPost]
        [HttpGet]
        [Route("[action]")]
        public IActionResult AdvanceResumeSearchData(AdvanceResumeSearch model)
        {
            List<SearchResumeListViewModel> lstResumeList = new List<SearchResumeListViewModel>();
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            try
            {
                lstResumeList = searchresumehandler.GetAdvanceSearchResumeList(model, user.UserId);
            }
            catch (UserNotFoundException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(SearchResumeController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));

            }
            return View(lstResumeList);
        }

        [HttpGet]
        [Route("[action]")]
        public IActionResult GetAdvacedSeachById(int Id)
        {
            List<AdvanceResumeSearch> lstAdvanceResumeSearch = new List<AdvanceResumeSearch>();
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);
            user = user ?? new UserViewModel();
            bool result = false;
            try
            {
                lstAdvanceResumeSearch = searchresumehandler.AdvanceSearchById(Id, user.UserId);
                result = true;
            }
            catch (UserNotFoundException ex)
            {
                result = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, user.UserId, typeof(SearchResumeController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));

            }
            return Json(new { result, lstAdvanceResumeSearch });
        }
    }
}