using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Employer.Dashboard
{
    public class JobSeekerViewModel
    {
        public string JobTitleByEmployer { get; set; }
        public string JobRoles { get; set; }
        public IList<UserViewModel> jobSeekers { get; set; }
    }
}
