import { Body, Controller, Delete, Get, Patch } from '@nestjs/common';
import { UsersService } from './users.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UpdateProfileDto, UpdatePreferencesDto, UpdateAvailabilityDto } from './dto/user.dto';

@Controller('me')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  me(@CurrentUser('id') userId: string) {
    return this.users.me(userId);
  }

  @Patch('profile')
  profile(@CurrentUser('id') userId: string, @Body() dto: UpdateProfileDto) {
    return this.users.updateProfile(userId, dto);
  }

  @Patch('preferences')
  preferences(@CurrentUser('id') userId: string, @Body() dto: UpdatePreferencesDto) {
    return this.users.updatePreferences(userId, dto);
  }

  @Get('availability')
  getAvailability(@CurrentUser('id') userId: string) {
    return this.users.getAvailability(userId);
  }

  @Patch('availability')
  availability(@CurrentUser('id') userId: string, @Body() dto: UpdateAvailabilityDto) {
    return this.users.updateAvailability(userId, dto);
  }

  @Delete()
  deleteAccount(@CurrentUser('id') userId: string) {
    return this.users.deleteAccount(userId);
  }
}
