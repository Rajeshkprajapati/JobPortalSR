﻿using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Data.DataModel.Admin.JobTitle
{
    public class JobTitleModel
    {
        public int JobTitleId { get; set; }
        public string JobTitleName { get; set; }
        public int JobIndustryAreaId { get; set; }
        public string UpdatedBy { get; set; }
        public string UpdatedDate { get; set; }
        public string SerialNo { get; set; }
    }
}
