using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Employer.Dashboard
{
    public class DashboardSummary
    {
        public int TotalProfileViewes { get; set; }
        public int TotalResumeList { get; set; }
        public int TotalMessages{ get; set; }
        public int RespondTime { get; set; }
    }
}
