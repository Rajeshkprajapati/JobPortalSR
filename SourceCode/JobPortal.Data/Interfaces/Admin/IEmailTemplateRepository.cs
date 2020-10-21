using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using JobPortal.Model.DataViewModel.Admin.Notifications;

namespace JobPortal.Data.Interfaces.Admin
{
    public interface IEmailTemplateRepository
    {
        bool UpdateEmailTemplate(EmailTemplateViewModel model, string userid);
    }
}
