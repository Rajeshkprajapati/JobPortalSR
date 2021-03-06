﻿using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.Net;
using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Business.Interfaces.Employer.SearchResume;
using JobPortal.Business.Shared;
using JobPortal.Data.DataModel.Shared;
using JobPortal.Data.Interfaces.Employer.SearchResume;
using JobPortal.Data.Interfaces.Shared;
using JobPortal.Model.DataViewModel.Employer.AdvanceSearch;
using JobPortal.Model.DataViewModel.Employer.SearchResume;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.Helpers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;

namespace JobPortal.Business.Handlers.Employer.SearchResume
{
    public class SearchResumeHandler : ISearchResumeHandler
    {
        private readonly ISearchResumeRepository _serarchresumeProcess;
        private IHostingEnvironment _hostingEnviroment;
        private readonly IMasterDataRepository _masterRepository;
        public SearchResumeHandler(IConfiguration configuration, IHostingEnvironment hostingEnvironment)
        {
            var factory = new ProcessorFactoryResolver<ISearchResumeRepository>(configuration);
            _serarchresumeProcess = factory.CreateProcessor();
            var masterfactory = new ProcessorFactoryResolver<IMasterDataRepository>(configuration);
            _masterRepository = masterfactory.CreateProcessor();
            _hostingEnviroment = hostingEnvironment;
        }
        public List<SearchResumeListViewModel> GetSearchResumeList(SearchResumeViewModel searches)
        {
            List<SearchResumeListViewModel> lstSearchedResume = new List<SearchResumeListViewModel>();
            var sFilters = new SearchResumeModel
            {
                Skills = searches.Skills,
                JobCategory = string.Join(Constants.CommaSeparator, searches.JobCategory),
                City = string.Join(Constants.CommaSeparator, searches.City),
                MinExp = searches.MinExp,
                MaxExp = searches.MaxExp
            };
            DataTable searchedResume = _serarchresumeProcess.GetSearchResumeList(sFilters);
            if (searchedResume.Rows.Count > 0)
            {
                for (int i = 0; i < searchedResume.Rows.Count; i++)
                {
                    string resumePath = Convert.ToString(searchedResume.Rows[i]["Resume"]);
                    if (!string.IsNullOrWhiteSpace(resumePath))
                    {
                        if (!File.Exists($"{_hostingEnviroment.WebRootPath}{resumePath}"))
                        {
                            resumePath = string.Empty;
                        }
                    }

                    var skillsObject = new SearchResumeListViewModel
                    {
                        Skills = JsonConvert.DeserializeObject<Skills>(Convert.ToString(searchedResume.Rows[i]["Skills"])),
                        FirstName = (searchedResume.Rows[i]["FirstName"] as string) ?? "",
                        LastName = (searchedResume.Rows[i]["LastName"] as string) ?? "",
                        Email = (searchedResume.Rows[i]["Email"] as string) ?? "",
                        Resume = resumePath,
                        UserId = (searchedResume.Rows[i]["UserId"] as int?) ?? 0,
                        CityName = (searchedResume.Rows[i]["CityName"] as string) ?? "",
                        JobIndustryAreaName = (searchedResume.Rows[i]["JobIndustryAreaName"] as string) ?? "",
                        JobTitle = (searchedResume.Rows[i]["JobTitleName"] as string) ?? "",
                        //Address = (searchedResume.Rows[i]["Address"] as string) ?? "",
                        AboutMe = (searchedResume.Rows[i]["AboutMe"] as string) ?? "",
                        ProfilePic = Convert.ToString(searchedResume.Rows[i]["ProfilePic"]),
                        CurrentSalary = Convert.ToString(searchedResume.Rows[i]["CurrentSalary"]),
                        ExpectedSalary = Convert.ToString(searchedResume.Rows[i]["ExpectedSalary"]),
                        //ProfileSummary = Convert.ToString(searchedResume.Rows[i]["ProfileSummary"]),
                        LinkedinProfile = Convert.ToString(searchedResume.Rows[i]["LinkedinProfile"]),
                        ExperienceDetails = JsonConvert.DeserializeObject<ExperienceDetails[]>(searchedResume.Rows[i]["ExperienceDetails"].ToString())
                    };
                    //var len = skillsObject.Skills.SkillSets.Length;
                    //if (skillsObject.Skills != null && skillsObject.Skills.SkillSets.Substring(len-1) != ",")
                    //{
                    //    skillsObject.Skills.SkillSets += ",";
                    //}
                    //skillsObject.Skills.SkillSets += Convert.ToString(searchedResume.Rows[i]["ITSkill"]);
                    lstSearchedResume.Add(skillsObject);
                    string picpath = Path.GetFullPath(_hostingEnviroment.WebRootPath + lstSearchedResume[i].ProfilePic);
                    if (!System.IO.File.Exists(picpath))
                    {
                        string fName = $@"\ProfilePic\" + "Avatar.jpg";
                        lstSearchedResume[i].ProfilePic = fName;
                    }
                }
                return lstSearchedResume;
            }
            throw new UserNotFoundException("Data Not found");
        }


        public SearchResumeListViewModel ShowCandidateDetails(int employerId, int jobSeekerId)
        {
            //var a = JsonConvert.DeserializeObject(skill).ToString();
            SearchResumeListViewModel model = new SearchResumeListViewModel();
            DataTable searchedResume = _serarchresumeProcess.ShowCandidateDetails(employerId, jobSeekerId);
            if (searchedResume.Rows.Count > 0)
            {
                EducationalDetails[] objEducationDetail = JsonConvert.DeserializeObject<EducationalDetails[]>(searchedResume.Rows[0]["EducationalDetails"].ToString());
                ExperienceDetails[] objExperience = JsonConvert.DeserializeObject<ExperienceDetails[]>(searchedResume.Rows[0]["ExperienceDetails"].ToString());
                model.Skills = new Skills();
                var skills = JsonConvert.DeserializeObject<Skills>(searchedResume.Rows[0]["Skills"].ToString());
                if (null != skills)
                {
                    model.Skills = skills;
                }
                string resumePath = Convert.ToString(searchedResume.Rows[0]["Resume"]);
                if (!string.IsNullOrWhiteSpace(resumePath))
                {
                    if (!File.Exists($"{_hostingEnviroment.WebRootPath}{resumePath}"))
                    {
                        resumePath = string.Empty;
                    }
                }
                model.ExperienceDetails = objExperience;
                model.EducationalDetails = objEducationDetail;
                if (model.EducationalDetails != null)
                {
                    foreach (EducationalDetails edu in model.EducationalDetails)
                    {
                        DataTable coursename = _masterRepository.GetCoursesById(Convert.ToInt32(edu.Course));
                        if (coursename != null && coursename.Rows.Count > 0)
                        {
                            edu.CourseName = coursename.Rows[0]["CourseName"] as string ?? "";
                        }
                    }
                }

                model.FirstName = Convert.ToString(searchedResume.Rows[0]["FirstName"]);
                model.LastName = Convert.ToString(searchedResume.Rows[0]["LastName"]);
                model.Email = Convert.ToString(searchedResume.Rows[0]["Email"]);
                model.Resume = resumePath;
                model.UserId = Convert.ToInt32(searchedResume.Rows[0]["UserId"]);
                model.CityCode = Convert.ToString(searchedResume.Rows[0]["CityCode"]);
                model.CityName = Convert.ToString(searchedResume.Rows[0]["CityName"]);
                model.JobIndustryAreaName = Convert.ToString(searchedResume.Rows[0]["JobIndustryAreaName"]);
                model.CreatedOn = Convert.ToDateTime(searchedResume.Rows[0]["CreatedOn"]);
                model.Address = Convert.ToString(searchedResume.Rows[0]["Address1"]);
                model.State = Convert.ToString(searchedResume.Rows[0]["State"]);
                model.StateName = Convert.ToString(searchedResume.Rows[0]["StateName"]);
                model.Country = Convert.ToString(searchedResume.Rows[0]["Country"]);
                model.MobileNo = Convert.ToString(searchedResume.Rows[0]["MobileNo"]);
                model.ProfilePic = Convert.ToString(searchedResume.Rows[0]["ProfilePic"]);
                model.AboutMe = searchedResume.Rows[0]["AboutMe"].ToString();
                model.LinkedinProfile = searchedResume.Rows[0]["LinkedinProfile"].ToString();
                model.JobTitle = searchedResume.Rows[0]["JobTitleName"].ToString();
                model.CountryName = searchedResume.Rows[0]["CountryName"].ToString();
                //model.TotalExperience = Convert.ToDouble(searchedResume.Rows[0]["TotalExperience"]);
                if (!Convert.IsDBNull(searchedResume.Rows[0]["TotalExperience"]))
                {
                    model.TotalExperience = Convert.ToDouble(searchedResume.Rows[0]["TotalExperience"]);
                }
                string dob = Convert.ToString(searchedResume.Rows[0]["DateOfBirth"] as string) ?? "";

                if (dob != null && dob != "")
                {
                    DateTime date = Convert.ToDateTime(dob);
                    model.DateOfBirth = Convert.ToString(DateTime.Now.Year - date.Year);
                }
                string picpath = System.IO.Path.GetFullPath(_hostingEnviroment.WebRootPath + model.ProfilePic);
                if (!System.IO.File.Exists(picpath))
                {
                    string fName = $@"\ProfilePic\" + "118_index.jpg";
                    model.ProfilePic = fName;
                }
                model.CurrentSalary = searchedResume.Rows[0]["CurrentSalary"].ToString();
                model.ExpectedSalary = searchedResume.Rows[0]["ExpectedSalary"].ToString();

                return model;
            }
            throw new UserNotFoundException("Data Not found");
        }

        public void LogSearchResumeList(SearchResumeViewModel searches, string userip, int empid)
        {
            try
            {

                //string ipinfo = new WebClient().DownloadString("http://ipinfo.io/" + "171.76.228.130");
                string ipinfo = new WebClient().DownloadString("http://ipinfo.io/" + userip);
                //var ipInfo = JsonConvert.DeserializeObject<IpInfo>(info);
                //RegionInfo myRI1 = new RegionInfo(ipInfo.Country);
                //ipInfo.Country = myRI1 != null ? myRI1.EnglishName : "";
                var search = JsonConvert.SerializeObject(searches);
                _serarchresumeProcess.LogSearchResumeList(search, userip, ipinfo, empid);
            }
            catch (Exception ex)
            {

            }

        }

        public List<CityViewModel> GetCityList()
        {
            DataTable city = _masterRepository.GetAllCitiesWithoutState();
            if (city.Rows.Count > 0)
            {
                List<CityViewModel> lstCity = new List<CityViewModel>();
                lstCity = ConvertDatatableToModelList.ConvertDataTable<CityViewModel>(city);
                return lstCity;
            }
            throw new UserNotFoundException("User not found");
        }
        public List<GenderViewModel> GetGenders()
        {
            DataTable genderdata = _masterRepository.GetAllGender(true);
            List<GenderViewModel> lstGender = new List<GenderViewModel>();
            if (genderdata.Rows.Count > 0)
            {
                lstGender = ConvertDatatableToModelList.ConvertDataTable<GenderViewModel>(genderdata);
            }
            return lstGender;
        }
        public IList<UserViewModel> GetEmployers(bool isAll)
        {
            DataTable dt = _masterRepository.GetEmployers(null, isAll);
            var employers = new List<UserViewModel>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                var emp = new UserViewModel()
                {
                    UserId = Convert.ToInt32(dt.Rows[i]["Userid"]),
                    FirstName = Convert.ToString(dt.Rows[i]["FirstName"]),
                    LastName = Convert.ToString(dt.Rows[i]["LastName"]),
                    CompanyName = Convert.ToString(dt.Rows[i]["CompanyName"]),
                    CityName = Convert.ToString(dt.Rows[i]["City"])

                };
                employers.Add(emp);

            }
            return employers;
        }

        public List<SearchResumeListViewModel> GetAdvanceSearchResumeList(AdvanceResumeSearch searches, int userId)
        {
            List<SearchResumeListViewModel> lstSearchedResume = new List<SearchResumeListViewModel>();
            DataTable searchedResume = _serarchresumeProcess.GetAdvanceSearchResumeList(searches, userId);
            if (searchedResume.Rows.Count > 0)
            {
                for (int i = 0; i < searchedResume.Rows.Count; i++)
                {
                    string resumePath = Convert.ToString(searchedResume.Rows[i]["Resume"]);
                    if (!string.IsNullOrWhiteSpace(resumePath))
                    {
                        if (!File.Exists($"{_hostingEnviroment.WebRootPath}{resumePath}"))
                        {
                            resumePath = string.Empty;
                        }
                    }

                    var skillsObject = new SearchResumeListViewModel
                    {
                        Skills = JsonConvert.DeserializeObject<Skills>(Convert.ToString(searchedResume.Rows[i]["Skills"])),
                        FirstName = (searchedResume.Rows[i]["FirstName"] as string) ?? "",
                        LastName = (searchedResume.Rows[i]["LastName"] as string) ?? "",
                        Email = (searchedResume.Rows[i]["Email"] as string) ?? "",
                        Resume = resumePath,
                        UserId = (searchedResume.Rows[i]["UserId"] as int?) ?? 0,
                        CityName = (searchedResume.Rows[i]["CityName"] as string) ?? "",
                        JobIndustryAreaName = (searchedResume.Rows[i]["JobIndustryAreaName"] as string) ?? "",
                        JobTitle = (searchedResume.Rows[i]["JobTitleName"] as string) ?? "",
                        //Address = (searchedResume.Rows[i]["Address"] as string) ?? "",
                        AboutMe = (searchedResume.Rows[i]["AboutMe"] as string) ?? "",
                        ProfilePic = Convert.ToString(searchedResume.Rows[i]["ProfilePic"]),
                        CurrentSalary = Convert.ToString(searchedResume.Rows[i]["CurrentSalary"]),
                        ExpectedSalary = Convert.ToString(searchedResume.Rows[i]["ExpectedSalary"]),
                        LinkedinProfile = Convert.ToString(searchedResume.Rows[i]["LinkedinProfile"]),
                        ExperienceDetails = JsonConvert.DeserializeObject<ExperienceDetails[]>(searchedResume.Rows[i]["ExperienceDetails"].ToString())
                    };
                    lstSearchedResume.Add(skillsObject);
                    string picpath = Path.GetFullPath(_hostingEnviroment.WebRootPath + lstSearchedResume[i].ProfilePic);
                    if (!System.IO.File.Exists(picpath))
                    {
                        string fName = $@"\ProfilePic\" + "Avatar.jpg";
                        lstSearchedResume[i].ProfilePic = fName;
                    }
                }
                return lstSearchedResume;
            }
            throw new UserNotFoundException("Data Not found");
        }
        public List<AdvanceResumeSearch> AdvanceSearchStates(int UserId)
        { 
            DataTable dt = _serarchresumeProcess.AdvanceSearchStates(UserId);
            var SearchStats = new List<AdvanceResumeSearch>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                var search = new AdvanceResumeSearch()
                {
                    id = Convert.ToInt32(dt.Rows[i]["Id"]),
                    HiringRequirement = Convert.ToString(dt.Rows[i]["HiringRequirement"]),
                    AllKeyword = Convert.ToString(dt.Rows[i]["AllKeyword"]),
                    skills = Convert.ToString(dt.Rows[i]["Skills"]),
                    isSavedSearch = Convert.ToBoolean(dt.Rows[i]["IsSavedSearch"])

                };
                SearchStats.Add(search);
                
            }
            return SearchStats;
            throw new UserNotFoundException("data not found");
           }

        public List<AdvanceResumeSearch> AdvanceSearchById(int Id,int UserId)
        {
            DataTable dt = _serarchresumeProcess.AdvanceSearchById(Id,UserId);
            var SearchStats = new List<AdvanceResumeSearch>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                var search = new AdvanceResumeSearch()
                {
                    HiringRequirement = Convert.ToString(dt.Rows[i]["HiringRequirement"]),
                    AnyKeyword = Convert.ToString(dt.Rows[i]["AnyKeyword"]),
                    AllKeyword = Convert.ToString(dt.Rows[i]["AllKeyword"]),
                    ExculudeKeyword = Convert.ToString(dt.Rows[i]["ExculudeKeyword"]),
                    MinExperiance = Convert.ToInt32(dt.Rows[i]["MinExperience"]),
                    MaxExperiance = Convert.ToInt32(dt.Rows[i]["MaxExperience"]),
                    MinSalary = Convert.ToString(dt.Rows[i]["MinSalary"]),
                    MaxSalary = Convert.ToString(dt.Rows[i]["MaxSalary"]),
                    CurrentLocation = Convert.ToString(dt.Rows[i]["CurrentLocation"]),
                    PreferredLocation1 = Convert.ToString(dt.Rows[i]["PreferredLocation1"]),
                    PreferredLocation2 = Convert.ToString(dt.Rows[i]["PreferredLocation2"]),
                    PreferredLocation3 = Convert.ToString(dt.Rows[i]["PreferredLocation3"]),
                    FuncationlArea = Convert.ToInt32(dt.Rows[i]["FuncationlArea"]),
                    JobIndustryAreaId = Convert.ToInt32(dt.Rows[i]["JobIndustryAreaId"]),
                    CurrentDesignation = Convert.ToString(dt.Rows[i]["CurrentDesignation"]),
                    NoticePeriod = Convert.ToString(dt.Rows[i]["NoticePeriod"]),
                    skills = Convert.ToString(dt.Rows[i]["Skills"]),
                    AgeFrom = Convert.ToInt32(dt.Rows[i]["AgeFrom"]),
                    AgeTo = Convert.ToInt32(dt.Rows[i]["AgeTo"]),
                    Gender = Convert.ToString(dt.Rows[i]["Gender"]),
                    CandidatesType = Convert.ToString(dt.Rows[i]["CandidatesType"]),
                    ShowCandidateSeeking = Convert.ToInt32(dt.Rows[i]["ShowCandidateSeeking"]),
                    isSavedSearch = Convert.ToBoolean(dt.Rows[i]["IsSavedSearch"]),

                };
                SearchStats.Add(search);

            }
            return SearchStats;
            throw new UserNotFoundException("data not found");
        }
    }
}
