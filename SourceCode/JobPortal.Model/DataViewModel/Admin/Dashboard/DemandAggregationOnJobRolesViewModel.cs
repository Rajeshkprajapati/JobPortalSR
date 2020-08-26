using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Admin.Dashboard
{
    public class DemandAggregationOnJobRolesViewModel
    {
        public int JobRoleId { get; set; }
        public string JobRole { get; set; }
        public int Year { get; set; }
        public int Month { get; set; }
        public DemandAggregationDataViewModel DemandAggregations {get;set;}
    }
}
