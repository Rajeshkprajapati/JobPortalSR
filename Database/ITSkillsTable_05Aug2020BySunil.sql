CREATE TABLE ITSkills
(
	Id  INT NOT NULL IDENTITY PRIMARY KEY,
	Skill VARCHAR(50),
	SkillVersion VARCHAR(50),
	LastUsed VARCHAR(10),
	ExperienceYear VARCHAR(10),
	ExperienceMonth VARCHAR(10),
	CreatedDate DATETIME,
	CreatedBy VARCHAR(50),
	UpdateDate DateTime,
	UpdatedBy VARCHAR(50)
)
