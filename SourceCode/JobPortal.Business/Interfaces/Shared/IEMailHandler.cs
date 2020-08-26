using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.Shared
{
    public interface IEMailHandler
    {
        void SendMail(EmailViewModel email, int userId,bool isInsertInDB=true);
        bool IsValidEmail(string email);
    }
}
