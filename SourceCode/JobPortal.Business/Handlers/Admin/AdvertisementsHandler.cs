using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Data.DataModel.Admin.Advertisement;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.Advertisements;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Business.Handlers.Admin
{
    public class AdvertisementsHandler : IAdvertisementsHandler
    {
        private readonly IAdvertisementsRepository _advertisementsRepository;
        public AdvertisementsHandler(IConfiguration configuration)
        {
            var factory = new ProcessorFactoryResolver<IAdvertisementsRepository>(configuration);
            _advertisementsRepository = factory.CreateProcessor();
        }


        public IEnumerable<AdvertisementsViewModel> GetAllData(int section=0)
        {
            var ads = _advertisementsRepository.GetAllData(section);
            IList<AdvertisementsViewModel> model = new List<AdvertisementsViewModel>();
            foreach(DataRow row in ads.Rows)
            {
                model.Add(new AdvertisementsViewModel {
                    Id= row["Id"] as int? ?? 0,
                    ImagePath = row["ImageUrl"] as string ?? "",
                    Section = row["Section"] as int? ?? 0,
                    Order = row["Order"] as int? ?? 0
                });
            }
            return model;
        }
        public bool AddAds(AdvertisementsViewModel model)
        {
            var ads = new AdvertisementDataModel
            {
                Id = model.Id,
                ImagePath = model.ImagePath,
                Section = model.Section,
                Order = model.Order
            };
            return _advertisementsRepository.AddAds(ads);
        }
        public bool UpdateAds(AdvertisementsViewModel model,int userid)
        {
            var ads = new AdvertisementDataModel
            {
                Id = model.Id,
                ImagePath = model.ImagePath,
                Section = model.Section,
                Order = model.Order
            };
            return _advertisementsRepository.UpdateAds(ads,userid);
        }
        public bool DeleteAds(int adid)
        {            
            return _advertisementsRepository.DeleteAds(adid);
        }
    }
}
