using JobPortal.Model.DataViewModel.Admin.Dashboard;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.FilesUtility;
using NPOI.SS.UserModel;
using System.Collections.Generic;

namespace JobPortal.Business.Interfaces.Admin
{
    public interface IDashboardHandler
    {
        IList<DemandAggregationDataOnQuarterViewModel> GetDemandAggregationDataOnQuarter(int userId, DemandAggregationSearchItems search);
        IList<JobTitleViewModel> GetJobTitles();
        IList<UserViewModel> GetEmployers(bool isAll=false);
        IList<StateViewModel> GetStates(string country);
        IList<DemandAggregationOnJobRolesViewModel> GetDemandAggregationDataOnJobRole(int userId, DemandAggregationSearchItems search);
        IList<DemandAggregationOnStatesViewModel> GetDemandAggregationOnState(int userId, DemandAggregationSearchItems search);
        IList<DemandAggregationDetailsViewModel> ViewDemandAggregationDetails(string onBasis, string value, DemandAggregationSearchItems search);
        IList<DemandAggregationOnEmployersViewModel> GetDemandAggregationDataOnEmployer(int userId, DemandAggregationSearchItems search);
        IWorkbook GetDemandAggregationReportData(DemandAggregationSearchItems search, FileExtensions fileExtension);
        List<CityViewModel> GetCityList(string StateCode);
    }
}
