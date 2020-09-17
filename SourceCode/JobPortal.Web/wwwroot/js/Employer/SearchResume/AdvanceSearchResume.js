function GetAdvanceSearchById(id) {
    SendAJAXRequest(`/SearchResume/GetAdvacedSeachById/?Id=${id}`, 'GET', {}, 'JSON', (result) => {
        if (result) {
            $('#HiringRequirement').val(result.lstAdvanceResumeSearch[0].hiringRequirement);
            $('#AnyKeyword').val(result.lstAdvanceResumeSearch[0].anyKeyword);
            $('#AllKeyword').val(result.lstAdvanceResumeSearch[0].allKeyword);
            $('#ExculudeKeyword').val(result.lstAdvanceResumeSearch[0].exculudeKeyword);
            $('#MinExperiance option:selected ').val(result.lstAdvanceResumeSearch[0].minExperiance);
            $('#MaxExperiance option:selected ').val(result.lstAdvanceResumeSearch[0].maxExperiance);
            $('#MinSalary').val(result.lstAdvanceResumeSearch[0].minSalary);
            $('#MaxSalary').val(result.lstAdvanceResumeSearch[0].maxSalary);
            $('#CurrentLocation').val(result.lstAdvanceResumeSearch[0].currentLocation);
            $('#PreferredLocation1').val(result.lstAdvanceResumeSearch[0].preferredLocation1);
            $('#PreferredLocation2').val(result.lstAdvanceResumeSearch[0].preferredLocation2);
            $('#PreferredLocation3').val(result.lstAdvanceResumeSearch[0].preferredLocation3);
            $('#FuncationlArea').val(result.lstAdvanceResumeSearch[0].funcationlArea);
            $('#JobIndustryAreaId').val(result.lstAdvanceResumeSearch[0].jobIndustryAreaId);
            $('#CurrentDesignation').val(result.lstAdvanceResumeSearch[0].currentDesignation);
            $('#NoticePeriod').val(result.lstAdvanceResumeSearch[0].noticePeriod);
            $('#AgeFrom').val(result.lstAdvanceResumeSearch[0].ageFrom);
            $('#AgeTo').val(result.lstAdvanceResumeSearch[0].ageTo);
            $('#gender').val(result.lstAdvanceResumeSearch[0].gender);
            $('#CandidatesType').val(result.lstAdvanceResumeSearch[0].candidatesType);
            $('#ShowCandidateWith').val(result.lstAdvanceResumeSearch[0].showCandidateWith);
            $('#ShowCandidateSeeking').val(result.lstAdvanceResumeSearch[0].showCandidateSeeking);
            $('#isSavedSearch').val(result.lstAdvanceResumeSearch[0].isSavedSearch);
           //InformationDialog('Information', result.errorMessage);
           
        } else {
            $('#loader').hide();
         }
    }, null, null);
}