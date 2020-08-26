using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Model.DataViewModel.TrainingPartner;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.TrainingPartner
{
    public interface ITrainingPartnerProfileHandler
    {
        UserViewModel GetTPDetail(int userid);
        bool UpdateTPDetail(UserViewModel user);
    }
}
