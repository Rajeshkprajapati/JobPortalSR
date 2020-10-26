using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Shared
{
    public class SearchJobViewModel
    {
        public string Skills { get; set; } = string.Empty;
        public string[] JobTitle { get; set; } = new string[0];
        public string[] JobCategory { get; set; } = new string[0];
        public int Experiance { get; set; } = -1;
        public int MinExperiance { get; set; } = -1;
        public int MaxExperiance { get; set; } = -1;
        public string[] City { get; set; } = new string[0];
        public string[] CompanyUserId { get; set; } = new string[0];
    }
}
