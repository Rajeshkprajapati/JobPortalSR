using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Employer.AdvanceSearch
{
    public class AdvanceResumeSearch
    {
        public string HiringRequirement { get; set; }
        public string AnyKeyword { get; set; }
        public string AllKeyword { get; set; }
        public string ExculudeKeyword { get; set;}
        public int MinExperiance { get; set; }
        public int MaxExperiance { get; set; }
        public string MinSalary { get; set; }
        public string MaxSalary { get; set; }
        public string CurrentLocation { get; set; }
        public string PreferredLocation1 { get; set; }
        public string PreferredLocation2 { get; set; }
        public string PreferredLocation3 { get; set; }
        public int FuncationlArea { get; set; }
        public int JobIndustryAreaId { get; set; }
        public string CurrentDesignation { get; set; }
        public string NoticePeriod { get; set; }
        //public int Undergraduatefrom { get; set; }
        //public int UndergraduateTo { get; set; }
        //public string SpecifyUnderGraduate { get; set; }
        //public int PostGraduatefrom { get; set; }
        //public int PostGraduateTo { get; set; }
        //public string SpecifyPostGraduatefrom { get; set; }
        public int AgeFrom { get; set; }
        public int AgeTo { get; set; }
        public string Gender { get; set; }
        public string CandidatesType { get; set; }
        public string ShowCandidateWith { get; set; }
        public int ShowCandidateSeeking { get; set; }
        public string CandidateShortedby { get; set; }
        public string CandidateActiveInmonth { get; set; }
        public string skills { get; set; }
        public bool isSavedSearch { get; set; }
        public int id { get; set; }

    }
}
