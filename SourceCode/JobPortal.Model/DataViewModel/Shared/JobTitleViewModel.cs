using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Shared
{
    public class JobTitleViewModel
    {
        public int JobTitleId { get; set; }
        public string JobTitleName { get; set; }
        public int JobIndustryAreaId { get; set; }
        public string UpdatedBy { get; set; }
        public string UpdatedDate { get; set; }
    }
}
