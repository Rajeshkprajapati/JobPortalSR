using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Data.DataModel.Admin.Designation;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using JobPortal.Model.DataViewModel.Admin.Designation;

namespace JobPortal.Business.Handlers.Admin
{
    public class DesignationHandler : IDesignationHandler
    {
        private readonly IDesignationRepository _userProcessor;
        public DesignationHandler(IConfiguration configuration)
        {
            var factory = new ProcessorFactoryResolver<IDesignationRepository>(configuration);
            _userProcessor = factory.CreateProcessor();
        }
        public List<DesignationViewModel> GetDesignationList()
        {
            DataTable dt = _userProcessor.GetDesignationList();
            List<DesignationViewModel> designationList = new List<DesignationViewModel>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                DesignationViewModel designation = new DesignationViewModel
                {
                    DesignationId = Convert.ToInt32(dt.Rows[i]["DesignationId"]),
                    Designation = Convert.ToString(dt.Rows[i]["Designation"]),
                    Abbrivation = Convert.ToString(dt.Rows[i]["Abbr"]),
                };
                designationList.Add(designation);
            }
            return (designationList);
        }

        public bool AddDesignation(DesignationViewModel designationViewModel)
        {
            DesignationModel designationModel = new DesignationModel
            {
                Designation = designationViewModel.Designation,
                Abbrivation = designationViewModel.Abbrivation
            };
            return _userProcessor.AddDesignation(designationModel);
        }
        public bool UpdateDesignation(DesignationViewModel designationViewModel)
        {

            DesignationModel designationModel = new DesignationModel
            {
                DesignationId = designationViewModel.DesignationId,
                Designation = designationViewModel.Designation,
                Abbrivation = designationViewModel.Abbrivation
            };
            return _userProcessor.UpdateDesignation(designationModel);

        }

        public bool DeleteDesignation(int designationid)
        {
            var result = _userProcessor.DeleteDesignation(designationid);
            if (result)
            {
                return true;
            }
            throw new DataNotFound("Unable to delete data");
        }
    }
}
