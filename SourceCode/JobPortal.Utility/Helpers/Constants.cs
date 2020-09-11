using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Helpers
{
    public class Constants
    {
        public const string PossiblitiesToRandomGenerator ="abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789";

        //  Session Keys
        public const string SessionKeyUserInfo= "_SessionKeyUserInfo";
        public const string SessionRedirectUrl = "_SessionRedirectUrl";

        //  Roles
        public const string AdminRole = "Admin";
        public const string CorporateRole = "Corporate";
        public const string StudentRole = "Student";
        public const string DemandAggregationRole = "Demand Aggregation";
        public const string StaffingPartnerRole = "Staffing Partner";
        public const string TrainingPartnerRole = "Training Partner";
        public const string AllRoles = "Corporate,Staffing Partner, Student, Training Partner,Admin,Consultant";
        public const string JobSeekers = "Student, Training Partner";
        public const string Employers = "Corporate,Staffing Partner,Consultant";
        public const string Consultant = "Consultant";

        


        //  Separators

        public const string CommaSeparator = ",";
        public const string JobPostingQuarterStartingMonthKey = "JobPostingQuarterStartingMonth";


        //  Notations

        public const string NotAvailalbe = "N/A";
    }
}
