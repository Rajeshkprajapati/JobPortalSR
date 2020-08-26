using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Handlers.DataProcessorFactory
{
    public abstract class ProcessorFactory<T>
    {
        public abstract T CreateProcessor();
    }
}
