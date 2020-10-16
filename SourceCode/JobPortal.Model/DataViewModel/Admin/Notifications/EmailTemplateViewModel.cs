using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Admin.Notifications
{
    public class EmailTemplateViewModel
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Subject { get; set; }
        public string EmailBody { get; set; }
        public int UserRole { get; set; }
        public string EmailId { get; set; }
    }
}
