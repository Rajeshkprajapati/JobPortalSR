using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Data.DataModel.Employer.JobPost
{
    public class EmploymentTypeModel
    {
        public int EmploymentTypeId { get; set; }
        public string EmploymentTypeName { get; set; }
        public bool Status { get; set; }
    }
}
