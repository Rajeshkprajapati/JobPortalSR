﻿using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Data.DataModel.Shared
{
    public class JobSearchModel
    {
        public string Skills { get; set; }
        public int JobRole { get; set; }
        public string JobCategory { get; set; }
        public int Experiance { get; set; }
        public string City { get; set; }
        public string CompanyUserId;
    }
}
