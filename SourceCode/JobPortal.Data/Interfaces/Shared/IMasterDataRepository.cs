using JobPortal.Data.DataModel.Employer.JobPost;
using JobPortal.Data.Repositories.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Shared
{
    public interface IMasterDataRepository
    {
        DataTable GetStates(string country);
        DataTable GetCities(string state);
        DataTable GetCourses(int cCategory);
        DataTable GetCoursesCategory();
        DataTable GetCoursesById(int courseid);
        DataTable GetEmployers(int? empId=null, bool isAll = false);
        DataTable GetCountries();
        DataTable GetJobTypes();
        DataTable GetJobRoles(int roleId=0);
        DataRow GetCityByCode(string cityCode);
        DataTable GetAllCitiesWithoutState();
        DataTable GetAllGender(bool withAll=false);
        DataTable GetMaritalStatusMaster();
        DataTable JobIndustryArea();
        DataTable GetJobTitlesById(int JobIndustryAreaId);
        DataTable GetJobSeekers(int MaxExp);
    }
}
