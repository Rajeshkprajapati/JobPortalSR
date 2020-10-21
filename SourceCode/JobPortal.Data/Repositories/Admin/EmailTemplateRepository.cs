using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Data;
using System.Data.SqlClient;
using JobPortal.Model.DataViewModel.Admin.Notifications;

namespace JobPortal.Data.Repositories.Admin
{
   public class EmailTemplateRepository: IEmailTemplateRepository
    {
        private readonly string connectionString;
        public EmailTemplateRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }
        public bool UpdateEmailTemplate(EmailTemplateViewModel model, string userid)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@Id",model.Id),
                        new SqlParameter("@UserId",userid),
                        new SqlParameter("@Name",model.Name),
                        new SqlParameter("@Subject",model.Subject),
                        new SqlParameter("@UserRole",model.UserRole),
                        new SqlParameter("@EmailBody",model.EmailBody),
                    };
                    var data =
                       SqlHelper.ExecuteNonQuery
                       (
                           connection,
                           CommandType.StoredProcedure,
                           "usp_UpdateEmailTemplate",
                           parameters
                           );
                    if (data > 0)
                    {
                        return true;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new Exception("Unable to delete data");
        }
    }
}
