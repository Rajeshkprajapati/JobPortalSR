﻿using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class FaildToApplyJob: ApplicationException
    {
        public FaildToApplyJob(string message) : base(message)
        {

        }

        public FaildToApplyJob(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
