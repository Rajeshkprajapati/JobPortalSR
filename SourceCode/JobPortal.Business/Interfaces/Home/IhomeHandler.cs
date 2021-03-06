﻿using JobPortal.Data.Interfaces.Employer.JobPost;
using JobPortal.Model.DataViewModel.Admin.JobIndustryArea;
using JobPortal.Model.DataViewModel.Admin.SuccessStory;
using JobPortal.Model.DataViewModel.Home;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.Home
{
    public interface IHomeHandler
    {
        List<CityViewModel> GetCityListByChar(string cityFirstChar);
        List<CityViewModel> GetAllCityList();
        List<JobTitleViewModel> GetJobListByChar(string jobFirstChar);
        List<CityViewModel> GetCityHasJobPostId();
        List<CityViewModel> GetCitiesWithJobSeekerInfo();
        List<SuccessStoryViewModel> GetSuccussStory();
        bool PostSuccessStory(SuccessStoryViewModel user);
        List<SearchJobListViewModel> GetFeaturedJobs();
        List<SearchJobListViewModel> ViewAllFeaturedJobs();
        List<PopulerSearchesViewModel> PopulerSearchesCategory();
        List<CounterLabelViewModel> GetCounterLabelData();
        List<PopulerSearchesViewModel> PopulerSearchesCity();
        List<SearchJobListViewModel> AllJobsByCategory(int categoryId);
        List<SearchJobListViewModel> AllJobsByCity(string CityCode);
        List<JobIndustryAreaViewModel> GetCategory();
        List<TopEmployerViewModel> TopEmployer();
        List<SearchJobListViewModel> GetAllCompanyList();
        List<SearchJobListViewModel> NasscomJobs();
        List<int> GetAplliedJobs(int userid);
        List<SuccessStoryVideoViewModel> GetSuccussStoryVideos();
        IList<JobTitleViewModel> GetAllJobRoles();
        List<CompanyViewModel> GetCompanyHasJobPostId();
        string GetContactUsEmail();
        string TalentConnectLink();
        string CandidateBulkUpload();
        string TPRegistrationGuide();
        List<SearchJobListViewModel> GetRecentJobs();
        List<SearchJobListViewModel> GetWalkInsJobs();
        bool EmployerFollower(int EmployerId, int UserId);
        List<PopulerSearchesViewModel> CategoryJobVacancies();
        List<PopulerSearchesViewModel> CityJobVacancies();
        List<PopulerSearchesViewModel> CompanyJobVacancies();
        List<SearchJobListViewModel> AllJobsByCompany(int UserId);
        List<SearchJobListViewModel> FreelancerJobs();
        List<JobTitleViewModel> GetJobTitleById(int JobIndustrialArea);
    }
}
