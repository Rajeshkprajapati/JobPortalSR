using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Data.DataModel.Admin.Dashboard
{
    public class DemandAggregationSearchFilters
    {
        public int UserId { get; set; }
        public string Employers { get; set; }
        public int FinancialYear { get; set; }

        public int UserRole { get; set; }
        public string JobRoles { get; set; }
        public string JobStates { get; set; }
    }
}
