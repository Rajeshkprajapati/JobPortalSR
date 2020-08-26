using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.JobSeeker
{
    public class ResumeViewModel
    {
        public UserViewModel PersonalDetails { get; set; }
        public IList<EducationalDetails> EducationalDetails { get; set; }
        public IList<ExperienceDetails> ExperienceDetails { get; set; }
        public Skills Skills { get; set; }
    }
}
