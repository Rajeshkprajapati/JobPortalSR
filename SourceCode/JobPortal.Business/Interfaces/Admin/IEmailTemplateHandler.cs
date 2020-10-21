using System;
using System.Collections.Generic;
using System.Text;
using JobPortal.Model.DataViewModel.Admin.Notifications;

namespace JobPortal.Business.Interfaces.Admin
{
   public interface IEmailTemplateHandler
    {
        List<EmailTemplateViewModel> GetEmailTemplates(int UserRole);
        bool UpdateEmailTemplate(EmailTemplateViewModel data, string userid);
    }
}
