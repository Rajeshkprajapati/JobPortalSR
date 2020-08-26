using JobPortal.Data.DataModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Shared
{
    public interface IBulkJobPostRepository
    {
        DataTable GetIdFromValue(string value, string valueFor);
        bool SaveDetailToAudit(BulkJobPostSummaryDetail detail);
        bool InsertCity(ref CityModel city);
        bool InsertState(ref StateModel state);
    }
}
