using JobPortal.Data.DataModel.Shared;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Data.Interfaces.Shared
{
    public interface IEmailRepository
    {
        bool SaveMailInformation(EmailModel email);
    }
}
