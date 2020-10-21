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
        bool InsertEmailTemplate(EmailTemplateViewModel data, string userid);
        bool DeleteUsersReviews(int id, int deletedBy);
    }
}
