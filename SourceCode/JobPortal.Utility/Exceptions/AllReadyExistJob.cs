using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
   public class AllReadyExistJob: ApplicationException
    {
        public AllReadyExistJob(string message) : base(message)
        {

        }
        public AllReadyExistJob(string message, Exception exception) : base(message)
        {

        }
    }
}
