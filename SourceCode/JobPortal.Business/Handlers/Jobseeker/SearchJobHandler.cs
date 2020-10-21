using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Business.Interfaces.Home;
using JobPortal.Business.Interfaces.Jobseeker;
using JobPortal.Business.Shared;
using JobPortal.Data.DataModel.Shared;
using JobPortal.Data.Interfaces.Jobseeker;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.Helpers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;

namespace JobPortal.Business.Handlers.Jobseeker
{
    public class SearchJobHandler : ISearchJobHandler
    {
        private readonly ISearchJobRepository _searchJobRepository;
        private readonly IHostingEnvironment _hostingEnviroment;
        private readonly IHomeHandler homeHandler;
        public SearchJobHandler(IConfiguration configuration, IHostingEnvironment hostingEnvironment, IHomeHandler _homeHandler)
        {
            var factory = new ProcessorFactoryResolver<ISearchJobRepository>(configuration);
            _searchJobRepository = factory.CreateProcessor();
            _hostingEnviroment = hostingEnvironment;
            homeHandler = _homeHandler;
        }

        public void LogSearchJob(SearchJobViewModel searches,string userip, int UserId)
        {
            try
            {

                //string ipinfo = new WebClient().DownloadString("http://ipinfo.io/" + "171.76.228.130");
                string ipinfo = new WebClient().DownloadString("http://ipinfo.io/" + userip);
                //var ipInfo = JsonConvert.DeserializeObject<IpInfo>(info);
                //RegionInfo myRI1 = new RegionInfo(ipInfo.Country);
                //ipInfo.Country = myRI1 != null ? myRI1.EnglishName : "";                
                var search = JsonConvert.SerializeObject(searches);
                _searchJobRepository.LogSearchJob(search, userip, ipinfo, UserId);
            }
            catch (Exception ex)
            {

            }
        }
       

        public List<SearchJobListViewModel> SearchJobList(SearchJobViewModel searches, int UserId)
        {
            //Microsoft.Extensions.Logging.Logger.Logger.WriteLog(Logger.Logtype.Information, JsonConvert.SerializeObject(searches), user.UserId, typeof(JobController), new Exception("Before search Info Logged"));
            var sModel = new JobSearchModel
            {
                Skills = searches.Skills,
                JobRole = searches.JobTitle,
                City = string.Join(Constants.CommaSeparator, searches.City),
                MinExperiance = searches.MinExperiance,
                MaxExperiance = searches.MaxExperiance,
                JobCategory = string.Join(Constants.CommaSeparator, searches.JobCategory),
                CompanyUserId = string.Join(Constants.CommaSeparator, searches.CompanyUserId)
            };
            //int quarterStartMonth = Convert.ToInt32(ConfigurationHelper.Config.GetSection(Constants.JobPostingQuarterStartingMonthKey).Value);
            DataTable jobList = _searchJobRepository.GetSearchJobList(sModel, UserId);
            List<SearchJobListViewModel> lstJobList = new List<SearchJobListViewModel>();
            if (jobList.Rows.Count > 0)
            {
                //lstJobList = ConvertDatatableToModelList.ConvertDataTable<SearchJobListViewModel>(jobList);
                foreach (DataRow row in jobList.Rows)
                {
                    lstJobList.Add(new SearchJobListViewModel
                    {
                        JobTitleByEmployer = Convert.ToString(row["JobTitleByEmployer"]),
                        Skills = Convert.ToString(row["Skills"]),
                        JobPostId = Convert.ToInt32(row["JobPostId"]),
                        CompanyLogo = Convert.ToString(row["CompanyLogo"]),
                        JobTitle = Convert.ToString(row["JobTitle"]),
                        EmploymentStatus = Convert.ToString(row["EmploymentStatus"]),
                        City = Convert.ToString(row["City"]),
                        HiringCriteria = Convert.ToString(row["HiringCriteria"]),
                        CompanyName = Convert.ToString(row["CompanyName"]),
                        CTC = Convert.ToString(row["CTC"]),
                        NumberOfDays = Convert.ToString(row["NumberOfDays"]),
                    });
                }
                var appliedJobs =homeHandler.GetAplliedJobs(UserId);
                for (int i = 0; i < lstJobList.Count; i++)
                {
                    //getting the all the jobs applied by user only if the user logged in
                    if (UserId != 0 && appliedJobs.Count > 0)
                    {
                        lstJobList[i].IsApplied = appliedJobs.Any(aj => aj == lstJobList[i].JobPostId);
                    }

                    //Handled if image url exist in db but not available physically
                    string picpath = System.IO.Path.GetFullPath(_hostingEnviroment.WebRootPath + lstJobList[i].CompanyLogo);
                    if (!System.IO.File.Exists(picpath))
                    {
                        string fName = $@"\ProfilePic\" + "Avatar_company.jpg";
                        lstJobList[i].CompanyLogo = fName;
                    }
                }
            }
            return lstJobList;
        }

    }
}
