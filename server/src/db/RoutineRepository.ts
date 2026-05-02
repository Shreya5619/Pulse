import { query } from "./db";

export interface RoutineBlock {
    id: string;
    userId: string;
    title: string;
    startTime: string; // HH:mm
    endTime: string;   // HH:mm
    category: 'sleep' | 'study' | 'commute' | 'buffer';
    days: number[]; // 0-6 (Sun-Sat)
}

export class RoutineRepository {
    private routines: RoutineBlock[] = [
        {
            id: 'routine_sleep',
            userId: 'demo-user',
            title: 'Sleep',
            startTime: '23:00',
            endTime: '07:00',
            category: 'sleep',
            days: [0, 1, 2, 3, 4, 5, 6]
        },
        {
            id: 'routine_study',
            userId: 'demo-user',
            title: 'Study block',
            startTime: '09:00',
            endTime: '11:00',
            category: 'study',
            days: [1, 2, 3, 4, 5]
        },
        {
            id: 'routine_commute',
            userId: 'demo-user',
            title: 'Usual commute',
            startTime: '08:30',
            endTime: '09:00',
            category: 'commute',
            days: [1, 2, 3, 4, 5]
        },
        {
            id: 'routine_buffer',
            userId: 'demo-user',
            title: 'Free buffer',
            startTime: '12:00',
            endTime: '13:00',
            category: 'buffer',
            days: [0, 1, 2, 3, 4, 5, 6]
        }
    ];

    async getForUser(userId: string): Promise<RoutineBlock[]> {
        return this.routines.filter(r => r.userId === userId || r.userId === 'demo-user');
    }

    async getForDay(userId: string, date: Date): Promise<RoutineBlock[]> {
        const day = date.getDay();
        return (await this.getForUser(userId)).filter(r => r.days.includes(day));
    }

    async addRoutine(userId: string, routine: Omit<RoutineBlock, 'id' | 'userId'>): Promise<RoutineBlock> {
        const newRoutine: RoutineBlock = {
            ...routine,
            id: `routine_${Date.now()}`,
            userId
        };
        this.routines.push(newRoutine);
        return newRoutine;
    }

    async updateRoutine(userId: string, routineId: string, updates: Partial<RoutineBlock>): Promise<void> {
        const index = this.routines.findIndex(r => r.id === routineId && (r.userId === userId || r.userId === 'demo-user'));
        if (index !== -1) {
            this.routines[index] = { ...this.routines[index], ...updates };
        }
    }

    async deleteRoutine(userId: string, routineId: string): Promise<void> {
        this.routines = this.routines.filter(r => !(r.id === routineId && (r.userId === userId || r.userId === 'demo-user')));
    }
}

export const routineRepo = new RoutineRepository();
