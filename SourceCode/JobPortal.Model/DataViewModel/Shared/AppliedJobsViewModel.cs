using JobPortal.Model.DataViewModel.Employer.JobPost;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Shared
{
    public class AppliedJobsViewModel
    {
        public JobPostViewModel JobDetail { get; set; }
        public UserViewModel UserDetail { get; set; }
        public DateTime AppliedOn { get; set; }
    }
}
