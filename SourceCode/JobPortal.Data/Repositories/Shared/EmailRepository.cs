﻿using JobPortal.Data.DataModel.Shared;
using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Shared;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace JobPortal.Data.Repositories.Shared
{
    public class EmailRepository: IEmailRepository
    {
        private readonly string connectionString;

        public EmailRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }

        public bool SaveMailInformation(EmailModel email)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@Body",email.Body),
                        new SqlParameter("@From",email.From),
                        new SqlParameter("@CreatedBy",email.InsertedBy),
                        new SqlParameter("@Subject",email.Subject),
                        new SqlParameter("@To",email.To),
                        new SqlParameter("@mailType",email.MailType)
                    };
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_InsertEmailQueueData",
                            parameters
                            );
                    if (result > 0)
                    {
                        return true;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotUpdatedException("Unable to insert email data in email queue, please contact your teck deck with your details.");
        }
    }
}
