using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace JobPortal.Business.Interfaces.Shared
{
    public interface IFileHandler
    {
        Task<MemoryStream> FileToStream(string filePath);
    }
}
