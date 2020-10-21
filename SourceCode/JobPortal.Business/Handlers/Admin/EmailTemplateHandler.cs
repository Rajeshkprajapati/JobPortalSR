using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Data.Interfaces.Shared;
using JobPortal.Model.DataViewModel.Admin.Notifications;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Business.Handlers.Admin
{
    public class EmailTemplateHandler: IEmailTemplateHandler
    {
        private readonly IEmailTemplateRepository emailTemplateRepository;
        private readonly IManageUserRepository _userProcessor;
        public EmailTemplateHandler(IConfiguration configuration)
        {
            var factory = new ProcessorFactoryResolver<IEmailTemplateRepository>(configuration);
            var mfactory = new ProcessorFactoryResolver<IManageUserRepository>(configuration);
            emailTemplateRepository = factory.CreateProcessor();
           
            _userProcessor = mfactory.CreateProcessor();
        }
        public List<EmailTemplateViewModel> GetEmailTemplates(int UserRole)
        {
            int Id = 0;
            DataTable dt = _userProcessor.EmailTemplates(UserRole, Id);
            List<EmailTemplateViewModel> templateList = new List<EmailTemplateViewModel>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                EmailTemplateViewModel emailTemplateList = new EmailTemplateViewModel()
                {
                    Id = Convert.ToInt32(dt.Rows[i]["Id"]),
                    Name = Convert.ToString(dt.Rows[i]["Name"]),
                    Subject = Convert.ToString(dt.Rows[i]["Subject"]),
                    EmailBody = Convert.ToString(dt.Rows[i]["EmailBody"]),
                    UserRole = Convert.ToInt32(dt.Rows[i]["UserRole"]),
                 };
                templateList.Add(emailTemplateList);
            }
            return (templateList);
        }
        public bool UpdateEmailTemplate(EmailTemplateViewModel data, string userid)
        {
            var model = new EmailTemplateViewModel()
            {
                Id = data.Id,
                Name = data.Name,
                Subject = data.Subject,
                UserRole = data.UserRole,
                EmailBody = data.EmailBody
            };
            var result = emailTemplateRepository.UpdateEmailTemplate(model, userid);
            if (result)
            {
                return true;
            }
            throw new Exception("Unable to Update data");
        }

        public bool InsertEmailTemplate(EmailTemplateViewModel data, string userid)
        {
            var model = new EmailTemplateViewModel()
            {
                Name = data.Name,
                Subject = data.Subject,
                UserRole = data.UserRole,
                EmailBody = data.EmailBody
            };
            var result = emailTemplateRepository.InsertTemplate(model, userid);
            if (result)
            {
                return true;
            }
            throw new Exception("Unable to Update data");
        }

        public bool DeleteUsersReviews(int id, int deletedBy)
        {
            var result = emailTemplateRepository.DeleteEmailTemplate(id, deletedBy);
            if (result)
            {
                return true;
            }
            throw new Exception("Unable to delete data");
        }
    }
}
